#!/usr/bin/env bash
# PROBE 62_elixir_syntax  (ticket 62)
# CLAIM under test (ticket 62 s.1): Elixir cannot call a PascalCase B# export
# with ordinary remote-call syntax; only apply/3 works. The ticket's table did
# not try a QUOTED function name (`:Shop."New"(1)`), nor dynamic/unquote calls.
# REFUTES the ticket's "only apply/3 is the way in" if any non-apply form below
# prints `ok -> ...`. REFUTES the ticket's SYNTAX_ERROR rows if a row it lists
# prints `ok`. Controls: `:"BSharp.Shop".new(1)` must PARSE but be UNDEF at run
# time (no such export) -- parse-ok is not call-ok; `apply` must run.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/env.sh"
export ELIXIR_ERL_OPTIONS="+fnu"
W="$(bs_scratch)"; trap 'rm -rf "$W"' EXIT
mkdir -p "$W/ebin"
"$BSC" --src-root "$REPO/compiler/examples" -o "$W/ebin" "$REPO/compiler/examples/Shop" >/dev/null || { echo "bsc failed"; exit 2; }
"$BSC" --src-root "$REPO/compiler/examples" -o "$W/ebin" "$REPO/compiler/examples/Shop/Reports" >/dev/null || true
echo "elixir: $(elixir --version 2>/dev/null | tail -1)"
echo "exports of :Shop: $(erl -noshell -pa "$W/ebin" -eval "io:format(\"~p\",[lists:sort(['Shop':module_info(exports)])]),halt()." 2>&1 | head -c 400)"
BS_EBIN="$W/ebin" elixir "$(dirname "${BASH_SOURCE[0]}")/62_elixir_syntax.exs"
