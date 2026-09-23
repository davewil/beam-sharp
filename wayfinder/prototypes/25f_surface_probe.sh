#!/usr/bin/env bash
# PROTOTYPE 25f — what today's compiler says about the LLM evaluation client.
#
# Throwaway. Ticket 25, exemplar 6. Each section decides a claim in
# 25f-llm-evaluation-client.md. Every refusal carries a control beside it, so a
# refusal cannot be an unrelated failure read as the one claimed.
#
#   ./25f_surface_probe.sh
#
# Requires: OTP 28, rebar3. Builds bsc if it is not already built. Reads the
# EXTRACTED exemplar, so run compiler/bin/extract-exemplars.sh first if the
# write-up has changed.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER="$HERE/../../compiler"
BSC="$COMPILER/_build/default/bin/bsc"
EXEMPLAR="$COMPILER/examples/exemplars/25f-llm-evaluation-client"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -x "$BSC" ]; then
    echo "building bsc..."
    (cd "$COMPILER" && rebar3 escriptize >/dev/null 2>&1)
fi

# One directory per probe, named after the module — F15's rule.
n=0
probe () {
    local label="$1" body="$2"
    shift 2
    n=$((n + 1))
    local dir="$WORK/p$n/P"
    mkdir -p "$dir"
    printf 'module P\n%s\n' "$body" > "$dir/p.bs"
    echo "--- $label ---"
    "$BSC" --src-root "$WORK/p$n" "$dir" "$@" 2>&1 | sed "s|$WORK/p$n/||" || true
    echo
}

# The exemplar itself, copied into a directory its `module` line matches.
triage () {
    local root="$1"
    mkdir -p "$root/Support/Triage"
    cp "$EXEMPLAR"/*.bs "$root/Support/Triage/"
}

echo "==================================================================="
echo "1. THE WALL — the module's one error, and the run behind it."
echo "==================================================================="
triage "$WORK/m1"
echo "--- the exemplar as written ---"
"$BSC" --src-root "$WORK/m1" "$WORK/m1/Support/Triage" 2>&1 | sed "s|$WORK/m1/Support/Triage/||" || true
echo

echo "CONTROL — Model.Id declared binary. The module compiles with no error,"
echo "so the wall above is the only one."
triage "$WORK/m2"
sed -i.bak 's/Id: string }/Id: binary }/' "$WORK/m2/Support/Triage/index.bs"
rm -f "$WORK/m2/Support/Triage/"*.bak
mkdir -p "$WORK/ebin"
"$BSC" -o "$WORK/ebin" --src-root "$WORK/m2" "$WORK/m2/Support/Triage" 2>&1 | sed "s|$WORK/m2/Support/Triage/||"
echo "bsc status: ${PIPESTATUS[0]}"
echo

echo "THE RUN — 25f_replay.erl drives Evaluate and Decide with ReqLLM's fixtures."
erlc +warnings_as_errors -o "$WORK/ebin" "$HERE/25f_replay.erl"
erl -noshell -pa "$WORK/ebin" -s '25f_replay' main
echo

echo "==================================================================="
echo "2. A LOWERCASE JSON KEY HAS NO SPELLING."
echo "==================================================================="
probe "a lowercase record field" 'record Q { instructions: string }
public string Go(string s)
Go(s) -> ToJson<Q>(Q { instructions = s })'

probe "ToJson over the record the author writes — compiles, wrong body" 'record Question { Type: string, Instructions: string }
public string Go(string s)
Go(s) -> ToJson<Question>(Question { Type = "noul", Instructions = s })' Go '"Is this urgent?"'

probe "a string key in a map pattern" 'public term Go(map<string, term> m)
Go({ "answers": a }) -> a'

probe "a field set validated against json:decode output" 'type Wire = { Model: string, Answers: map<string, term> }
public result<Wire, ValidationError> Go(term t)
Go(t) -> ValidateAs<Wire>(t)' Go '#{<<"model">> => <<"jev">>, <<"answers">> => #{}}'

probe "a map literal" 'public term Go(string s)
Go(s) -> #{ "type" => "noul" }'

echo "CONTROL — the pair list and :maps.find, which the exemplar uses."
probe "CONTROL: what works" 'using :json {
    term encode(term t)
}
using :erlang {
    binary iolist_to_binary(term d)
}
using :maps {
    map<term, term> from_list(list<(binary, term)> pairs)
}
public binary Go(string s)
Go(s) -> :erlang.iolist_to_binary(:json.encode(:maps.from_list([("type", "noul"), ("instructions", s)])))' Go '"Is this urgent?"'

echo "==================================================================="
echo "3. A TYPED GETTER IS REFUSED BOTH WAYS."
echo "==================================================================="
probe "T only in the return" 'public result<T, ValidationError> Get<T>(term x)
Get(x) -> ValidateAs<T>(x)'
probe "T given a witness parameter" 'public result<T, ValidationError> Get<T>(T witness, term x)
Get(w, x) -> ValidateAs<T>(x)'
probe "CONTROL: the ground getter" 'public result<int, ValidationError> Get(term x)
Get(x) -> ValidateAs<int>(x)' Get 7

echo "==================================================================="
echo "5. json:decode CANNOT BE DECLARED OVER term."
echo "==================================================================="
probe "result<term, foreign_error>" 'using :json {
    result<term, foreign_error> decode(binary b)
}
public term Go(binary b)
Go(b) -> :json.decode(b)'
probe "CONTROL: the six members the decoder returns" 'type Json = map<term, term> | list<term> | binary | int | float | atom
using :json {
    result<Json, foreign_error> decode(binary b)
}
public result<Json, foreign_error> Go(binary b)
Go(b) -> :json.decode(b)' Go '"{nope"'

echo "==================================================================="
echo "6. THE DEFECT — ticket 12 §2's own example, with and without a field."
echo "==================================================================="
events () {
    printf 'record OrderPlaced    { Id: %s }\nrecord OrderShipped   { Id: %s }\nrecord OrderCancelled { Id: %s }\ntype Event = OrderPlaced | OrderShipped | OrderCancelled\n' "$1" "$1" "$1"
}
probe "fields { Id: :x } — refused, as ticket 12 says" "$(events ':x')
public atom Handle(Event e)
Handle(OrderPlaced p)  -> :placed
Handle(OrderShipped s) -> :shipped
Handle(_)              -> :other"
probe "fields { Id: int } — ADMITTED, and the catch-all swallows a cancellation" "$(events int)
public atom Handle(Event e)
Handle(OrderPlaced p)  -> :placed
Handle(OrderShipped s) -> :shipped
Handle(_)              -> :other" Handle "{Kind = :'P.OrderCancelled', Id = 1}"
probe "CONTROL: { Id: int } with no catch-all — the checker names the case" "$(events int)
public atom Handle(Event e)
Handle(OrderPlaced p)  -> :placed
Handle(OrderShipped s) -> :shipped"

echo "==================================================================="
echo "7. A THIRD PROVIDER, AND A USER-DECLARED BEHAVIOUR."
echo "==================================================================="
triage "$WORK/m3"
sed -i.bak -e 's/Id: string }/Id: binary }/' \
    -e 's/type Provider = :typesafe | :openrouter/type Provider = :typesafe | :openrouter | :vercel/' \
    "$WORK/m3/Support/Triage/index.bs"
rm -f "$WORK/m3/Support/Triage/"*.bak
echo "--- :vercel added to Provider ---"
"$BSC" --src-root "$WORK/m3" "$WORK/m3/Support/Triage" 2>&1 | sed "s|$WORK/m3/Support/Triage/||" || true
echo
probe "behaviour Provider" 'behaviour Provider
public int Go(int n)
Go(n) -> n'
