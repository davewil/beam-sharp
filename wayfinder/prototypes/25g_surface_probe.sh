#!/usr/bin/env bash
# PROTOTYPE 25g — what today's compiler says about the B# Jev.Server.
#
# Throwaway. Ticket 25, exemplar 7. Builds three modules from the extracted
# exemplars, each in a directory its `module` line matches: 25f's
# Support.Triage (the transport), and 25g's Jev and Triage, whose sections
# carry a `jev_` / `triage_` prefix the extractor needs and this script drops.
# Every refusal carries a control beside it.
#
#   ./25g_surface_probe.sh
#
# Requires: OTP 28, rebar3. Builds bsc if it is not already built. Reads the
# EXTRACTED exemplars, so run compiler/bin/extract-exemplars.sh first if a
# write-up has changed.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILER="$HERE/../../compiler"
BSC="$COMPILER/_build/default/bin/bsc"
EX="$COMPILER/examples/exemplars"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -x "$BSC" ]; then
    echo "building bsc..."
    (cd "$COMPILER" && rebar3 escriptize >/dev/null 2>&1)
fi

# The three modules, as written, under one source root.
tree () {
    local root="$1" f
    mkdir -p "$root/Support/Triage" "$root/Jev" "$root/Triage"
    cp "$EX"/25f-llm-evaluation-client/*.bs "$root/Support/Triage/"
    for f in "$EX"/25g-jev-server/jev_*.bs;    do cp "$f" "$root/Jev/$(basename "$f" | sed 's/^jev_//')"; done
    for f in "$EX"/25g-jev-server/triage_*.bs; do cp "$f" "$root/Triage/$(basename "$f" | sed 's/^triage_//')"; done
}

build () {
    local root="$1" m
    for m in Support/Triage Jev Triage; do
        echo "--- $m"
        "$BSC" --src-root "$root" "$root/$m" 2>&1 | sed "s|$root/||" | head -4
    done
}

n=0
probe () {
    local label="$1" body="$2"
    shift 2
    n=$((n + 1))
    local dir="$WORK/p$n/P"
    mkdir -p "$dir"
    printf 'module P\n%s\n' "$body" > "$dir/p.bs"
    echo "--- $label ---"
    "$BSC" --src-root "$WORK/p$n" "$dir" "$@" 2>&1 | sed "s|$WORK/p$n/||" | head -4 || true
    echo
}

echo "==================================================================="
echo "1. AS WRITTEN — it compiles, and it runs."
echo "==================================================================="
echo "Until F60 (2026-09-24) this stopped on 'no type named Down', and before"
echo "the F58 fix a string-keyed brace crashed bsc behind it. Section 6 keeps"
echo "that repro."
tree "$WORK/a"
mkdir -p "$WORK/ebin"
for m in Support/Triage Jev Triage; do
    echo "--- $m"
    "$BSC" -o "$WORK/ebin" --src-root "$WORK/a" "$WORK/a/$m" 2>&1 | sed "s|$WORK/a/||" | head -4
done
echo

echo "THE RUN — 25g_replay.erl: Jev's four README issues at once, and a crash."
erlc +warnings_as_errors -o "$WORK/ebin" "$HERE/25g_replay.erl"
erl -noshell -pa "$WORK/ebin" -s '25g_replay' main 2>&1 | grep -v '^Error in process\|^{transport_down\|^=\|^ \|^$'
echo

echo "==================================================================="
echo "3. A NARROWED HandleInfo IS ADMITTED, AND A STRAY MESSAGE KILLS IT."
echo "==================================================================="
mkdir -p "$WORK/s/Srv"
cat > "$WORK/s/Srv/srv.bs" <<'EOF'
module Srv

behaviour GenServer

public (:ok, int) Init(int seed)
Init(seed) -> (:ok, seed)

public (:reply, int, int) HandleCall(term req, term from, int state)
HandleCall(req, from, state) -> (:reply, state, state)

public (:noreply, int) HandleCast(term msg, int state)
HandleCast(msg, state) -> (:noreply, state)

public (:noreply, int) HandleInfo((:jev, int) msg, int state)
HandleInfo((:jev, n), state) -> (:noreply, state + n)
EOF
cat > "$WORK/stray.erl" <<'EOF'
-module(stray).
-export([main/0]).
main() ->
    {ok, P} = gen_server:start('Srv', 1, []),
    P ! {jev, 5},
    io:format("CONTROL: after (:jev, 5) the state is ~p~n", [gen_server:call(P, x)]),
    MRef = monitor(process, P),
    P ! stray,
    receive {'DOWN', MRef, process, P, {R, _}} -> io:format("after one stray atom: died, ~p~n", [R])
    after 500 -> io:format("after one stray atom: alive~n") end,
    halt().
EOF
"$BSC" -o "$WORK/ebin" --src-root "$WORK/s" "$WORK/s/Srv"
erlc -o "$WORK/ebin" "$WORK/stray.erl"
erl -noshell -pa "$WORK/ebin" -s stray main 2>&1 | grep -v '^=\|^\*\*\|^ \|^$'
echo

echo "==================================================================="
echo "4. pid IS A TYPE SINCE F60; 5. NO USER BEHAVIOUR; 6. THE F58 CRASH, FIXED."
echo "==================================================================="
probe "since F60: pid" 'public pid Me(pid p)
Me(p) -> p'
probe "behaviour Jev" 'behaviour Jev
public int Go(int n)
Go(n) -> n'
probe "since the F58 fix: a string-keyed brace where map<term, term> is expected" 'public map<term, term> Go(string t)
Go(t) -> { "title" = t }' Go '"x"'
probe "CONTROL: the same with a name key" 'public map<term, term> Go(string t)
Go(t) -> { Title = t }' Go '"x"'
