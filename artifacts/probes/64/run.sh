#!/usr/bin/env bash
# Ticket 64 probes. Needs erl, elixir, gleam on PATH and a built bsc ($BSC).
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
BSC=${BSC:-$HERE/../../../compiler/_build/default/bin/bsc}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
n=0
decl(){ # decl <label> <return-type> [extra decls]
  n=$((n+1)); local d="$W/D$n"; mkdir -p "$d/D$n"
  printf 'module D%s\n%s\npublic %s F(int x)\nF(x) -> raise :stub\n' "$n" "${3:-}" "$2" > "$d/D$n/d.bs"
  # a body that cannot typecheck is fine: we only want the DECLARATION verdict, so ask for the API
  local out; out=$(cd "$d" && "$BSC" --api D$n 2>&1 | head -2 | tr '\n' ' ' | cut -c1-170)
  printf '%-34s %s\n' "$1" "${out:-OK}"
}
echo "=== P1: what does the declaration verdict look like today? (bsc --api D)"
decl "option<int>"                  "option<int>"
decl "option<atom>"                 "option<atom>"
decl "option<term>"                 "option<term>"
decl "option<map<string, term>>"    "option<map<string, term>>"
decl "option<list<term>>"           "option<list<term>>"
decl "result<int, atom>"            "result<int, atom>"
decl "result<term, atom>"           "result<term, atom>"
decl "result<int, term>   (Q3)"     "result<int, term>"
decl "result<atom, binary>"         "result<atom, binary>"
decl "result<atom, atom>"           "result<atom, atom>"
decl "result<(atom, binary), binary>" "result<(atom, binary), binary>"
decl "option<option<int>>"          "option<option<int>>"
decl "hand-rolled (:ok,term)|:absent" "(:ok, term) | :absent"
decl "hand-rolled (:some,term)|:nothing" "(:some, term) | :nothing"
decl "record wrapper | :nothing"    "Found | :nothing" "record Found { Value: term }"

echo "--- the full text an author sees for option<term>:"
mkdir -p "$W/Z/Z"; printf 'module Z\npublic option<term> F(int x)\nF(x) -> raise :stub\n' > "$W/Z/Z/z.bs"; (cd "$W/Z" && "$BSC" --api Z 2>&1 | head -12)

echo "=== P2: a GENERIC returning option<T>, instantiated at T = term (is the collapse caught at the call?)"
mkdir -p "$W/G/G"; cat > "$W/G/G/g.bs" <<'B'
module G
public option<T> Wrap<T>(T x, bool keep)
Wrap(x, true) -> x
Wrap(_, false) -> :nothing

public option<int> AtInt(int x)
AtInt(x) -> Wrap(x, true)

public term AtTerm(term x)
AtTerm(x) -> Wrap(x, true)

public bool Present(term x)
Present(x) -> Check(Wrap(x, false))

private bool Check(term r)
Check(:nothing) -> false
Check(_) -> true
B
(cd "$W/G" && "$BSC" G 2>&1 | head -12)

echo "=== P3: the hazard in one program — a stored :nothing is indistinguishable from an absent key (Erlang, executed)"
erl -noshell -eval '
  M = #{present => nothing, other => 1},
  Bare = fun(K) -> maps:get(K, M, nothing) end,
  Tagged = fun(K) -> case maps:find(K, M) of {ok, V} -> {ok, V}; error -> absent end end,
  io:format("bare   present-with-value-nothing: ~p~n", [Bare(present)]),
  io:format("bare   absent key                : ~p   <- identical~n", [Bare(missing)]),
  io:format("tagged present-with-value-nothing: ~p~n", [Tagged(present)]),
  io:format("tagged absent key                : ~p~n", [Tagged(missing)]),
  halt().'

echo "=== P4: the price of a tag, in BEAM terms (erts_debug:flat_size words; 8 B/word on 64-bit)"
erl -noshell -eval '
  W = fun(T) -> erts_debug:flat_size(T) end,
  io:format("bare int 5               : ~p words~n", [W(5)]),
  io:format("bare small map value     : ~p words~n", [W(#{a=>1})]),
  io:format("{ok,5}                   : ~p words~n", [W({ok,5})]),
  io:format("{some,5}                 : ~p words~n", [W({some,5})]),
  io:format("{ok,#{a=>1}}             : ~p words (tag adds ~p)~n", [W({ok,#{a=>1}}), W({ok,#{a=>1}})-W(#{a=>1})]),
  halt().'

echo "=== P4b: lookup cost, compiled (see bench64.erl)"
erlc -o "$W" "$HERE/bench64.erl" && erl -noshell -pa "$W" -eval 'bench64:main(), halt().'

echo "=== P2b: execute the generic: Wrap(:nothing, true) must be PRESENT, and is it?"
mkdir -p "$W/H/H"; cat > "$W/H/H/h.bs" <<'B'
module H
public option<T> Wrap<T>(T x, bool keep)
Wrap(x, true) -> x
Wrap(_, false) -> :nothing

public bool PresentIfKept(term x)
PresentIfKept(x) -> Check(Wrap(x, true))

private bool Check(term r)
Check(:nothing) -> false
Check(_) -> true
B
(cd "$W/H" && "$BSC" H PresentIfKept ":nothing"; "$BSC" H PresentIfKept "5"; "$BSC" --api H 2>&1 | head -4)

echo "=== P5: blast radius if option<T> itself were tagged (corpus counts, run from repo root)"
R=$(cd "$HERE/../../.." && pwd)
printf 'option< sites in .bs under compiler/examples : %s (in %s files)\n' "$(grep -ro 'option<' --include=*.bs "$R/compiler/examples" | wc -l)" "$(grep -rl 'option<' --include=*.bs "$R/compiler/examples" | wc -l)"
printf ':nothing sites in .bs under compiler/examples: %s\n' "$(grep -ro ':nothing' --include=*.bs "$R/compiler/examples" | wc -l)"
printf 'option< lines in compiler/test/*.erl          : %s\n' "$(grep -r 'option<' --include=*.erl "$R/compiler/test" | wc -l)"

echo "=== P6: neighbours, executed"
if command -v gleam >/dev/null; then
  mkdir -p "$W/gl/src"; printf 'name = "g64"\nversion = "1.0.0"\n' > "$W/gl/gleam.toml"
  cp "$HERE/gl/src/g64.gleam" "$W/gl/src/"; (cd "$W/gl" && gleam build >/dev/null 2>&1)
  erl -noshell -pa "$W/gl/build/dev/erlang/g64/ebin" -eval 'io:format("gleam Some(5)=~p None=~p Ok=~p Error=~p Some(None)=~p~n",[g64:some(),g64:none(),g64:ok(),g64:err(),g64:nested()]),halt().'
fi
elixir -e 'IO.inspect({Map.fetch(%{a: nil}, :a), Map.fetch(%{}, :a), Map.get(%{a: nil}, :a), Map.get(%{}, :a)}, label: "elixir {fetch present-nil, fetch absent, get present-nil, get absent}")' 2>&1 | grep -v warning

echo "=== P7: the tagged type is ALREADY writable by an author, generically, and keeps present-:nothing distinct from absent"
mkdir -p "$W/T/T"; cat > "$W/T/T/t.bs" <<'B'
module T
type Maybe<T> = (:some, T) | :nothing
public Maybe<term> Find(term k)
Find(k) -> (:some, k)
public term Or(Maybe<term> m, term d)
Or((:some, v), d) -> v
Or(:nothing, d) -> d
public Maybe<int> FindI(int k)
FindI(k) -> :nothing
B
(cd "$W/T" && "$BSC" T Or "(:some, :nothing)" ":dflt"; "$BSC" T Or ":nothing" ":dflt"; "$BSC" --api T 2>&1 | head -5)
mkdir -p "$W/V/V"; printf 'module V\ntype maybe<T> = (:some, T) | :nothing\n' > "$W/V/V/v.bs"; (cd "$W/V" && "$BSC" V 2>&1 | head -1)
