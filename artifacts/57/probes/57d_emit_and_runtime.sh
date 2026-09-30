#!/usr/bin/env bash
# 57d: what changes in the emitted code and in run-time behaviour when `-5` is an e_int (variant A2)
# instead of {e_neg,{e_int,5}} (baseline / B variants)?   usage: B=/tmp/bsc57[-A2] ./57d_emit_and_runtime.sh
. "$(dirname "$0")/common.sh"
mkdir -p "$work/N"; cat > "$work/N/a.bs" <<'BS'
module N

public int Lit()
Lit() -> -5

public int Mul()
Mul() -> -5 * 2

public int Sub()
Sub() -> 10 - -5

public int Neg(int x)
Neg(x) -> -x

public int Mixed(int x)
Mixed(x) -> -x + -3

public int Paren()
Paren() -> -(5)

public int Div()
Div() -> -7 / 2

public int Rem()
Rem() -> -7 % 3
BS
cd "$work"
for f in Lit Mul Sub Paren Div Rem; do printf '%-6s => ' $f; $BSC N/a.bs $f 2>&1 | tail -1; done
printf 'Neg 4 => '; $BSC N/a.bs Neg 4 2>&1 | tail -1
printf 'Mixed 4 => '; $BSC N/a.bs Mixed 4 2>&1 | tail -1
cat > show.erl <<'ERL'
-module(show).
-export([main/0]).
main() ->
    {ok, Fs} = file:consult("N.abstr"),
    [io:format("~p~n", [F]) || F <- lists:flatten(Fs), is_tuple(F), element(1, F) =:= function,
                               lists:member(element(3, F), ['Lit', 'Mul', 'Sub'])],
    {beam_file, _, _, _, _, Code} = beam_disasm:file("N.beam"),
    io:format("--- beam_disasm of Lit~n"),
    [io:format("~p~n", [C]) || {function, 'Lit', _, _, C} <- Code].
ERL
erlc show.erl
$BSC N/a.bs   # compile only: writes N.abstr and N.beam here
echo "--- emitted abstract format (N.abstr) for Lit / Mul / Sub"
erl -noshell -eval 'show:main(), halt().'
